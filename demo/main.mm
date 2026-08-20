#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <stdexcept>

#include <QApplication>
#include <QCoreApplication>
#include <QFormLayout>
#include <QLabel>
#include <QPushButton>
#include <QSpinBox>
#include <QVBoxLayout>
#include <QWidget>

@interface CounterModel : NSObject
@property(nonatomic) NSInteger count;
@end

@implementation CounterModel
@synthesize count = _count;
@end

static void throwObjectiveCProbe(void)
{
    @throw [NSException exceptionWithName:@"DemoObjectiveCException"
                                   reason:@"Objective-C exception probe"
                                 userInfo:nil];
}

static void throwCppProbe(void)
{
    throw std::runtime_error("C++ exception raised by a Qt signal handler");
}

static bool runObjectiveCExceptionProbe(void)
{
    @try
    {
        throwObjectiveCProbe();
    }
    @catch (NSException *exception)
    {
        std::printf("objc-exception: %s\n", exception.reason.UTF8String);
        return true;
    }
    return false;
}

static bool runCppExceptionProbe(void)
{
    try
    {
        throwCppProbe();
    }
    catch (const std::exception &exception)
    {
        std::printf("cpp-exception: %s\n", exception.what());
        return true;
    }
    return false;
}

static int runHeadlessSmoke(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    CounterModel *model = [CounterModel new];
    model.count = 7;
    NSInteger value = model.count;
    BOOL objcExceptionCaught = runObjectiveCExceptionProbe();
    BOOL cppExceptionCaught = runCppExceptionProbe();
    BOOL ok = value == 7 && objcExceptionCaught && cppExceptionCaught;
    std::printf("objc-model: count=%ld\n", (long)value);
    [model release];
    return ok ? 0 : 1;
}

int main(int argc, char **argv)
{
    if (argc > 1 && std::strcmp(argv[1], "--headless") == 0)
        return runHeadlessSmoke(argc, argv);

    auto *app = new QApplication(argc, argv);
    CounterModel *model = [CounterModel new];
    auto *window = new QWidget;
    window->setWindowTitle(QStringLiteral("GNUstep Objective-C + Qt Wasm"));
    auto *layout = new QVBoxLayout(window);
    auto *title = new QLabel(QStringLiteral("Objective-C model + Qt view"));
    auto *description = new QLabel(QStringLiteral(
        "The model is an Objective-C NSObject. Qt is the view and controller."));
    auto *count = new QLabel;
    auto *increment = new QPushButton(QStringLiteral("Increment model"));
    auto *setValue = new QSpinBox;
    setValue->setRange(0, 1000);
    auto *setButton = new QPushButton(QStringLiteral("Set model value"));
    auto *objcExceptionButton = new QPushButton(QStringLiteral(
        "Throw Objective-C exception"));
    auto *cppExceptionButton = new QPushButton(QStringLiteral(
        "Throw C++ exception in Qt callback"));
    auto *exceptionStatus = new QLabel(QStringLiteral("No exception probe run"));

    layout->addWidget(title);
    layout->addWidget(description);
    layout->addWidget(count);
    layout->addWidget(increment);
    auto *form = new QFormLayout;
    form->addRow(QStringLiteral("New value"), setValue);
    form->addWidget(setButton);
    layout->addLayout(form);
    layout->addWidget(objcExceptionButton);
    layout->addWidget(cppExceptionButton);
    layout->addWidget(exceptionStatus);

    auto updateCount = [model, count]
    {
        count->setText(QStringLiteral("count = %1").arg(model.count));
    };
    updateCount();
    QObject::connect(increment, &QPushButton::clicked, [model, count]
    {
        model.count = model.count + 1;
        count->setText(QStringLiteral("count = %1").arg(model.count));
    });
    QObject::connect(setButton, &QPushButton::clicked,
                     [model, count, setValue]
    {
        model.count = setValue->value();
        count->setText(QStringLiteral("count = %1").arg(model.count));
    });
    QObject::connect(objcExceptionButton, &QPushButton::clicked,
                     [exceptionStatus]
    {
        @try
        {
            throwObjectiveCProbe();
        }
        @catch (NSException *exception)
        {
            exceptionStatus->setText(QStringLiteral(
                "Caught Objective-C exception: %1").arg(
                    QString::fromUtf8(exception.reason.UTF8String)));
        }
    });
    QObject::connect(cppExceptionButton, &QPushButton::clicked,
                     [exceptionStatus]
    {
        try
        {
            throwCppProbe();
        }
        catch (const std::exception &exception)
        {
            exceptionStatus->setText(QStringLiteral(
                "Caught C++ exception in Qt callback: %1").arg(
                    QString::fromUtf8(exception.what())));
        }
    });

    window->resize(620, 360);
    window->show();
#ifdef __EMSCRIPTEN__
    return 0;
#else
    int result = app->exec();
    [model release];
    delete window;
    delete app;
    return result;
#endif
}
